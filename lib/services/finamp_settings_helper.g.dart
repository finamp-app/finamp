// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off


part of 'finamp_settings_helper.dart';

// **************************************************************************
// _FinampSettingsGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint, unused_element

/// Generated setters for all finampSettings.  Must be directly accessed until
/// static extension methods are added to dart
extension FinampSetters on FinampSettingsHelper {
  static void setIsOffline(bool newIsOffline) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.isOffline = newIsOffline;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShouldTranscode(bool newShouldTranscode) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.shouldTranscode = newShouldTranscode;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setTranscodeBitrate(int newTranscodeBitrate) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.transcodeBitrate = newTranscodeBitrate;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAndroidStopForegroundOnPause(
    bool newAndroidStopForegroundOnPause,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.androidStopForegroundOnPause =
        newAndroidStopForegroundOnPause;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowTabs(ContentType tabContentType, bool newValue) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    try {
      finampSettingsTemp.showTabs[tabContentType] = newValue;
    } on UnsupportedError {
      // We were using the default const map directly.  Clone to allow modifications.
      finampSettingsTemp.showTabs = Map.from(finampSettingsTemp.showTabs);
      finampSettingsTemp.showTabs[tabContentType] = newValue;
    }
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setOnlyShowFavorites(bool newOnlyShowFavorites) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.onlyShowFavorites = newOnlyShowFavorites;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setTrackShuffleItemCount(int newTrackShuffleItemCount) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.trackShuffleItemCount = newTrackShuffleItemCount;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setContentViewType(ContentViewType newContentViewType) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.contentViewType = newContentViewType;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowTextOnGridView(bool newShowTextOnGridView) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showTextOnGridView = newShowTextOnGridView;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setUseCoverAsBackground(bool newUseCoverAsBackground) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.useCoverAsBackground = newUseCoverAsBackground;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setBufferDurationSeconds(int newBufferDurationSeconds) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.bufferDurationSeconds = newBufferDurationSeconds;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setDisableGesture(bool newDisableGesture) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.disableGesture = newDisableGesture;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setTabSortBy(ContentType tabContentType, SortBy newValue) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    try {
      finampSettingsTemp.tabSortBy[tabContentType] = newValue;
    } on UnsupportedError {
      // We were using the default const map directly.  Clone to allow modifications.
      finampSettingsTemp.tabSortBy = Map.from(finampSettingsTemp.tabSortBy);
      finampSettingsTemp.tabSortBy[tabContentType] = newValue;
    }
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setTabSortOrder(ContentType tabContentType, SortOrder newValue) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    try {
      finampSettingsTemp.tabSortOrder[tabContentType] = newValue;
    } on UnsupportedError {
      // We were using the default const map directly.  Clone to allow modifications.
      finampSettingsTemp.tabSortOrder = Map.from(
        finampSettingsTemp.tabSortOrder,
      );
      finampSettingsTemp.tabSortOrder[tabContentType] = newValue;
    }
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setTabOrder(List<ContentType> newTabOrder) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    if (finampSettingsTemp.tabOrder == newTabOrder) {
      newTabOrder = newTabOrder.toList();
    }
    finampSettingsTemp.tabOrder = newTabOrder;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowFastScroller(bool newShowFastScroller) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showFastScroller = newShowFastScroller;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setLoopMode(FinampLoopMode newLoopMode) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.loopMode = newLoopMode;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAutoloadLastQueueOnStartup(
    bool newAutoloadLastQueueOnStartup,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.autoloadLastQueueOnStartup =
        newAutoloadLastQueueOnStartup;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setVolumeNormalizationActive(bool newVolumeNormalizationActive) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.volumeNormalizationActive = newVolumeNormalizationActive;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setVolumeNormalizationIOSBaseGain(
    double newVolumeNormalizationIOSBaseGain,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.volumeNormalizationIOSBaseGain =
        newVolumeNormalizationIOSBaseGain;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setVolumeNormalizationMode(
    VolumeNormalizationMode newVolumeNormalizationMode,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.volumeNormalizationMode = newVolumeNormalizationMode;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setHasCompletedDownloadsServiceMigration(
    bool newHasCompletedDownloadsServiceMigration,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.hasCompletedDownloadsServiceMigration =
        newHasCompletedDownloadsServiceMigration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setRequireWifiForDownloads(bool newRequireWifiForDownloads) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.requireWifiForDownloads = newRequireWifiForDownloads;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setOnlyShowFullyDownloaded(bool newOnlyShowFullyDownloaded) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.onlyShowFullyDownloaded = newOnlyShowFullyDownloaded;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowDownloadsWithUnknownLibrary(
    bool newShowDownloadsWithUnknownLibrary,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showDownloadsWithUnknownLibrary =
        newShowDownloadsWithUnknownLibrary;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setMaxConcurrentDownloads(int newMaxConcurrentDownloads) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.maxConcurrentDownloads = newMaxConcurrentDownloads;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setDownloadWorkers(int newDownloadWorkers) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.downloadWorkers = newDownloadWorkers;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setResyncOnStartup(bool newResyncOnStartup) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.resyncOnStartup = newResyncOnStartup;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPreferQuickSyncs(bool newPreferQuickSyncs) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.preferQuickSyncs = newPreferQuickSyncs;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setHasCompletedIsarUserMigration(
    bool newHasCompletedIsarUserMigration,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.hasCompletedIsarUserMigration =
        newHasCompletedIsarUserMigration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setDownloadTranscodingCodec(
    FinampTranscodingCodec? newDownloadTranscodingCodec,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.downloadTranscodingCodec = newDownloadTranscodingCodec;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShouldTranscodeDownloads(
    TranscodeDownloadsSetting newShouldTranscodeDownloads,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.shouldTranscodeDownloads = newShouldTranscodeDownloads;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setDownloadTranscodeBitrate(int? newDownloadTranscodeBitrate) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.downloadTranscodeBitrate = newDownloadTranscodeBitrate;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShouldRedownloadTranscodes(
    bool newShouldRedownloadTranscodes,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.shouldRedownloadTranscodes =
        newShouldRedownloadTranscodes;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setEnableVibration(bool newEnableVibration) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.enableVibration = newEnableVibration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPlayerScreenCoverMinimumPadding(
    double newPlayerScreenCoverMinimumPadding,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.playerScreenCoverMinimumPadding =
        newPlayerScreenCoverMinimumPadding;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPrioritizeCoverFactor(double newPrioritizeCoverFactor) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.prioritizeCoverFactor = newPrioritizeCoverFactor;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setSuppressPlayerPadding(bool newSuppressPlayerPadding) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.suppressPlayerPadding = newSuppressPlayerPadding;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setHidePlayerBottomActions(bool newHidePlayerBottomActions) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.hidePlayerBottomActions = newHidePlayerBottomActions;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setReportQueueToServer(bool newReportQueueToServer) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.reportQueueToServer = newReportQueueToServer;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPeriodicPlaybackSessionUpdateFrequencySeconds(
    int newPeriodicPlaybackSessionUpdateFrequencySeconds,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.periodicPlaybackSessionUpdateFrequencySeconds =
        newPeriodicPlaybackSessionUpdateFrequencySeconds;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowArtistsTracksSection(bool newShowArtistsTracksSection) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showArtistsTracksSection = newShowArtistsTracksSection;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowArtistChipImage(bool newShowArtistChipImage) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showArtistChipImage = newShowArtistChipImage;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPlaybackSpeed(double newPlaybackSpeed) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.playbackSpeed = newPlaybackSpeed;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPlaybackSpeedVisibility(
    PlaybackSpeedVisibility newPlaybackSpeedVisibility,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.playbackSpeedVisibility = newPlaybackSpeedVisibility;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setDefaultDownloadLocation(String? newDefaultDownloadLocation) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.defaultDownloadLocation = newDefaultDownloadLocation;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAllowSplitScreen(bool newAllowSplitScreen) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.allowSplitScreen = newAllowSplitScreen;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setSplitScreenPlayerWidth(double newSplitScreenPlayerWidth) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.splitScreenPlayerWidth = newSplitScreenPlayerWidth;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setTrackOfflineFavorites(bool newTrackOfflineFavorites) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.trackOfflineFavorites = newTrackOfflineFavorites;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowProgressOnNowPlayingBar(
    bool newShowProgressOnNowPlayingBar,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showProgressOnNowPlayingBar =
        newShowProgressOnNowPlayingBar;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setStartInstantMixForIndividualTracks(
    bool newStartInstantMixForIndividualTracks,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.startInstantMixForIndividualTracks =
        newStartInstantMixForIndividualTracks;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowLyricsTimestamps(bool newShowLyricsTimestamps) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showLyricsTimestamps = newShowLyricsTimestamps;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setLyricsAlignment(LyricsAlignment newLyricsAlignment) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.lyricsAlignment = newLyricsAlignment;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowStopButtonOnMediaNotification(
    bool newShowStopButtonOnMediaNotification,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showStopButtonOnMediaNotification =
        newShowStopButtonOnMediaNotification;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowSeekControlsOnMediaNotification(
    bool newShowSeekControlsOnMediaNotification,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showSeekControlsOnMediaNotification =
        newShowSeekControlsOnMediaNotification;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setLyricsFontSize(LyricsFontSize newLyricsFontSize) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.lyricsFontSize = newLyricsFontSize;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowLyricsScreenAlbumPrelude(
    bool newShowLyricsScreenAlbumPrelude,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showLyricsScreenAlbumPrelude =
        newShowLyricsScreenAlbumPrelude;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setKeepScreenOnOption(KeepScreenOnOption newKeepScreenOnOption) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.keepScreenOnOption = newKeepScreenOnOption;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setKeepScreenOnWhilePluggedIn(
    bool newKeepScreenOnWhilePluggedIn,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.keepScreenOnWhilePluggedIn =
        newKeepScreenOnWhilePluggedIn;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setHasDownloadedPlaylistInfo(bool newHasDownloadedPlaylistInfo) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.hasDownloadedPlaylistInfo = newHasDownloadedPlaylistInfo;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setTranscodingStreamingFormat(
    FinampTranscodingStreamingFormat newTranscodingStreamingFormat,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.transcodingStreamingFormat =
        newTranscodingStreamingFormat;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setFeatureChipsConfiguration(
    FinampFeatureChipsConfiguration newFeatureChipsConfiguration,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.featureChipsConfiguration = newFeatureChipsConfiguration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowCoversOnAlbumScreen(bool newShowCoversOnAlbumScreen) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showCoversOnAlbumScreen = newShowCoversOnAlbumScreen;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setBufferDisableSizeConstraints(
    bool newBufferDisableSizeConstraints,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.bufferDisableSizeConstraints =
        newBufferDisableSizeConstraints;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setBufferSizeMegabytes(int newBufferSizeMegabytes) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.bufferSizeMegabytes = newBufferSizeMegabytes;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setDownloadSizeWarningCutoff(int newDownloadSizeWarningCutoff) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.downloadSizeWarningCutoff = newDownloadSizeWarningCutoff;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAllowDeleteFromServer(bool newAllowDeleteFromServer) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.allowDeleteFromServer = newAllowDeleteFromServer;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setOneLineMarqueeTextButton(bool newOneLineMarqueeTextButton) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.oneLineMarqueeTextButton = newOneLineMarqueeTextButton;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowAlbumReleaseDateOnPlayerScreen(
    bool newShowAlbumReleaseDateOnPlayerScreen,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showAlbumReleaseDateOnPlayerScreen =
        newShowAlbumReleaseDateOnPlayerScreen;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setReleaseDateFormat(ReleaseDateFormat newReleaseDateFormat) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.releaseDateFormat = newReleaseDateFormat;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setLastUsedDownloadLocationId(
    String? newLastUsedDownloadLocationId,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.lastUsedDownloadLocationId =
        newLastUsedDownloadLocationId;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAudioFadeOutDuration(Duration newAudioFadeOutDuration) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.audioFadeOutDuration = newAudioFadeOutDuration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAudioFadeInDuration(Duration newAudioFadeInDuration) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.audioFadeInDuration = newAudioFadeInDuration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAutoOffline(AutoOfflineOption newAutoOffline) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.autoOffline = newAutoOffline;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAutoOfflineListenerActive(bool newAutoOfflineListenerActive) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.autoOfflineListenerActive = newAutoOfflineListenerActive;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setItemSwipeActionLeftToRight(
    ItemSwipeActions newItemSwipeActionLeftToRight,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.itemSwipeActionLeftToRight =
        newItemSwipeActionLeftToRight;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setItemSwipeActionRightToLeft(
    ItemSwipeActions newItemSwipeActionRightToLeft,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.itemSwipeActionRightToLeft =
        newItemSwipeActionRightToLeft;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setDefaultArtistType(ArtistType newDefaultArtistType) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.defaultArtistType = newDefaultArtistType;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setCurrentVolume(double newCurrentVolume) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.currentVolume = newCurrentVolume;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPlayOnStaleDelay(int newPlayOnStaleDelay) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.playOnStaleDelay = newPlayOnStaleDelay;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPlayOnReconnectionDelay(int newPlayOnReconnectionDelay) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.playOnReconnectionDelay = newPlayOnReconnectionDelay;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setEnablePlayon(bool newEnablePlayon) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.enablePlayon = newEnablePlayon;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAutoReloadQueue(bool newAutoReloadQueue) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.autoReloadQueue = newAutoReloadQueue;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowShuffleButtonOnMediaNotification(
    bool newShowShuffleButtonOnMediaNotification,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showShuffleButtonOnMediaNotification =
        newShowShuffleButtonOnMediaNotification;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setShowFavoriteButtonOnMediaNotification(
    bool newShowFavoriteButtonOnMediaNotification,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.showFavoriteButtonOnMediaNotification =
        newShowFavoriteButtonOnMediaNotification;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setScreenSize(ScreenSize? newScreenSize) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.screenSize = newScreenSize;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGenreCuratedItemSelectionTypeTracks(
    CuratedItemSelectionType newGenreCuratedItemSelectionTypeTracks,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.genreCuratedItemSelectionTypeTracks =
        newGenreCuratedItemSelectionTypeTracks;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGenreCuratedItemSelectionTypeAlbums(
    CuratedItemSelectionType newGenreCuratedItemSelectionTypeAlbums,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.genreCuratedItemSelectionTypeAlbums =
        newGenreCuratedItemSelectionTypeAlbums;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGenreCuratedItemSelectionTypeArtists(
    CuratedItemSelectionType newGenreCuratedItemSelectionTypeArtists,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.genreCuratedItemSelectionTypeArtists =
        newGenreCuratedItemSelectionTypeArtists;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGenreItemSectionsOrder(
    List<GenreItemSections> newGenreItemSectionsOrder,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    if (finampSettingsTemp.genreItemSectionsOrder ==
        newGenreItemSectionsOrder) {
      newGenreItemSectionsOrder = newGenreItemSectionsOrder.toList();
    }
    finampSettingsTemp.genreItemSectionsOrder = newGenreItemSectionsOrder;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGenreFilterArtistScreens(bool newGenreFilterArtistScreens) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.genreFilterArtistScreens = newGenreFilterArtistScreens;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGenreListsInheritSorting(bool newGenreListsInheritSorting) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.genreListsInheritSorting = newGenreListsInheritSorting;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGenreItemSectionFilterChipOrder(
    List<CuratedItemSelectionType> newGenreItemSectionFilterChipOrder,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    if (finampSettingsTemp.genreItemSectionFilterChipOrder ==
        newGenreItemSectionFilterChipOrder) {
      newGenreItemSectionFilterChipOrder = newGenreItemSectionFilterChipOrder
          .toList();
    }
    finampSettingsTemp.genreItemSectionFilterChipOrder =
        newGenreItemSectionFilterChipOrder;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setApplyFilterOnGenreChipTap(bool newApplyFilterOnGenreChipTap) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.applyFilterOnGenreChipTap = newApplyFilterOnGenreChipTap;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setArtistCuratedItemSelectionType(
    CuratedItemSelectionType newArtistCuratedItemSelectionType,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.artistCuratedItemSelectionType =
        newArtistCuratedItemSelectionType;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setArtistItemSectionFilterChipOrder(
    List<CuratedItemSelectionType> newArtistItemSectionFilterChipOrder,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    if (finampSettingsTemp.artistItemSectionFilterChipOrder ==
        newArtistItemSectionFilterChipOrder) {
      newArtistItemSectionFilterChipOrder = newArtistItemSectionFilterChipOrder
          .toList();
    }
    finampSettingsTemp.artistItemSectionFilterChipOrder =
        newArtistItemSectionFilterChipOrder;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setArtistItemSectionsOrder(
    List<ArtistItemSections> newArtistItemSectionsOrder,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    if (finampSettingsTemp.artistItemSectionsOrder ==
        newArtistItemSectionsOrder) {
      newArtistItemSectionsOrder = newArtistItemSectionsOrder.toList();
    }
    finampSettingsTemp.artistItemSectionsOrder = newArtistItemSectionsOrder;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAutoSwitchItemCurationType(
    bool newAutoSwitchItemCurationType,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.autoSwitchItemCurationType =
        newAutoSwitchItemCurationType;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGenreFilterPlaylists(bool newGenreFilterPlaylists) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.genreFilterPlaylists = newGenreFilterPlaylists;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setSleepTimer(SleepTimer? newSleepTimer) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.sleepTimer = newSleepTimer;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setClearQueueOnStopEvent(bool newClearQueueOnStopEvent) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.clearQueueOnStopEvent = newClearQueueOnStopEvent;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPlaybackPitch(double newPlaybackPitch) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.playbackPitch = newPlaybackPitch;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setSyncPlaybackSpeedAndPitch(bool newSyncPlaybackSpeedAndPitch) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.syncPlaybackSpeedAndPitch = newSyncPlaybackSpeedAndPitch;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setUseHighContrastColors(bool newUseHighContrastColors) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.useHighContrastColors = newUseHighContrastColors;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setHasCompletedDownloadsFileOwnerMigration(
    bool newHasCompletedDownloadsFileOwnerMigration,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.hasCompletedDownloadsFileOwnerMigration =
        newHasCompletedDownloadsFileOwnerMigration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setTileAdditionalInfoType(
    ContentType tabContentType,
    TileAdditionalInfoType newValue,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    try {
      finampSettingsTemp.tileAdditionalInfoType[tabContentType] = newValue;
    } on UnsupportedError {
      // We were using the default const map directly.  Clone to allow modifications.
      finampSettingsTemp.tileAdditionalInfoType = Map.from(
        finampSettingsTemp.tileAdditionalInfoType,
      );
      finampSettingsTemp.tileAdditionalInfoType[tabContentType] = newValue;
    }
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setRpcEnabled(bool newRpcEnabled) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.rpcEnabled = newRpcEnabled;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setRpcIcon(DiscordRpcIcon newRpcIcon) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.rpcIcon = newRpcIcon;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAutoExpandPlayerScreen(bool newAutoExpandPlayerScreen) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.autoExpandPlayerScreen = newAutoExpandPlayerScreen;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPreferAddingToFavoritesOverPlaylists(
    bool newPreferAddingToFavoritesOverPlaylists,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.preferAddingToFavoritesOverPlaylists =
        newPreferAddingToFavoritesOverPlaylists;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPreviousTracksExpanded(bool newPreviousTracksExpanded) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.previousTracksExpanded = newPreviousTracksExpanded;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAutoplayRestoredQueue(bool newAutoplayRestoredQueue) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.autoplayRestoredQueue = newAutoplayRestoredQueue;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPreferNextUpPrepending(bool newPreferNextUpPrepending) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.preferNextUpPrepending = newPreferNextUpPrepending;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setRememberLastUsedPlaybackActionRowPage(
    bool newRememberLastUsedPlaybackActionRowPage,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.rememberLastUsedPlaybackActionRowPage =
        newRememberLastUsedPlaybackActionRowPage;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setLastUsedPlaybackActionRowPage(
    PlaybackActionRowPage newLastUsedPlaybackActionRowPage,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.lastUsedPlaybackActionRowPage =
        newLastUsedPlaybackActionRowPage;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAccentColor(Color? newAccentColor) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.accentColor = newAccentColor;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setThemeMode(ThemeMode newThemeMode) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.themeMode = newThemeMode;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setLocale(Locale? newLocale) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.locale = newLocale;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setHasCompletedThemeModeLocaleMigration(
    bool newHasCompletedThemeModeLocaleMigration,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.hasCompletedThemeModeLocaleMigration =
        newHasCompletedThemeModeLocaleMigration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setSystemAccentColor(Color? newSystemAccentColor) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.systemAccentColor = newSystemAccentColor;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setUseSystemAccentColor(bool newUseSystemAccentColor) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.useSystemAccentColor = newUseSystemAccentColor;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setUseMonochromeIcon(bool newUseMonochromeIcon) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.useMonochromeIcon = newUseMonochromeIcon;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setLastUsedPlaybackActionRowPageForQueueMenu(
    PlaybackActionRowPage newLastUsedPlaybackActionRowPageForQueueMenu,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.lastUsedPlaybackActionRowPageForQueueMenu =
        newLastUsedPlaybackActionRowPageForQueueMenu;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setRadioEnabled(bool newRadioEnabled) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.radioEnabled = newRadioEnabled;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setRadioMode(RadioMode newRadioMode) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.radioMode = newRadioMode;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setDuckOnAudioInterruption(bool newDuckOnAudioInterruption) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.duckOnAudioInterruption = newDuckOnAudioInterruption;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setForceAudioOffloadingOnAndroid(
    bool newForceAudioOffloadingOnAndroid,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.forceAudioOffloadingOnAndroid =
        newForceAudioOffloadingOnAndroid;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setMultichannelHandlingSetting(
    MultichannelHandlingSetting newMultichannelHandlingSetting,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.multichannelHandlingSetting =
        newMultichannelHandlingSetting;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setPreviousTracksPersistenceMode(
    PreviousTracksPersistenceMode newPreviousTracksPersistenceMode,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.previousTracksPersistenceMode =
        newPreviousTracksPersistenceMode;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setHomeScreenConfiguration(
    FinampHomeScreenConfiguration newHomeScreenConfiguration,
  ) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.homeScreenConfiguration = newHomeScreenConfiguration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setGridImageSize(int newGridImageSize) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.gridImageSize = newGridImageSize;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setAmoledTheme(bool newAmoledTheme) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.amoledTheme = newAmoledTheme;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setUseAndroidGainEffect(bool newUseAndroidGainEffect) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.useAndroidGainEffect = newUseAndroidGainEffect;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setHomeScreenImageSize(int newHomeScreenImageSize) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.homeScreenImageSize = newHomeScreenImageSize;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setClientCertificate(ClientCertificate? newClientCertificate) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.clientCertificate = newClientCertificate;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }

  static void setBufferDuration(Duration newBufferDuration) {
    FinampSettings finampSettingsTemp = FinampSettingsHelper.finampSettings;
    finampSettingsTemp.bufferDuration = newBufferDuration;
    Hive.box<FinampSettings>(
      "FinampSettings",
    ).put("FinampSettings", finampSettingsTemp);
  }
}

/// Generated providers to easily watch only specific fields in finampSettings
extension FinampSettingsProviderSelectors on StreamProvider<FinampSettings> {
  ProviderListenable<bool> get isOffline =>
      finampSettingsProvider.select((value) => value.requireValue.isOffline);
  ProviderListenable<bool> get shouldTranscode => finampSettingsProvider.select(
    (value) => value.requireValue.shouldTranscode,
  );
  ProviderListenable<int> get transcodeBitrate => finampSettingsProvider.select(
    (value) => value.requireValue.transcodeBitrate,
  );
  ProviderListenable<bool> get androidStopForegroundOnPause =>
      finampSettingsProvider.select(
        (value) => value.requireValue.androidStopForegroundOnPause,
      );
  ProviderListenable<bool?> showTabs(ContentType tabContentType) =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showTabs[tabContentType],
      );
  ProviderListenable<bool> get onlyShowFavorites => finampSettingsProvider
      .select((value) => value.requireValue.onlyShowFavorites);
  ProviderListenable<int> get trackShuffleItemCount => finampSettingsProvider
      .select((value) => value.requireValue.trackShuffleItemCount);
  ProviderListenable<ContentViewType> get contentViewType =>
      finampSettingsProvider.select(
        (value) => value.requireValue.contentViewType,
      );
  ProviderListenable<bool> get showTextOnGridView => finampSettingsProvider
      .select((value) => value.requireValue.showTextOnGridView);
  ProviderListenable<bool> get useCoverAsBackground => finampSettingsProvider
      .select((value) => value.requireValue.useCoverAsBackground);
  ProviderListenable<int> get bufferDurationSeconds => finampSettingsProvider
      .select((value) => value.requireValue.bufferDurationSeconds);
  ProviderListenable<bool> get disableGesture => finampSettingsProvider.select(
    (value) => value.requireValue.disableGesture,
  );
  ProviderListenable<SortBy?> tabSortBy(ContentType tabContentType) =>
      finampSettingsProvider.select(
        (value) => value.requireValue.tabSortBy[tabContentType],
      );
  ProviderListenable<SortOrder?> tabSortOrder(ContentType tabContentType) =>
      finampSettingsProvider.select(
        (value) => value.requireValue.tabSortOrder[tabContentType],
      );
  ProviderListenable<List<ContentType>> get tabOrder =>
      finampSettingsProvider.select((value) => value.requireValue.tabOrder);
  ProviderListenable<bool> get showFastScroller => finampSettingsProvider
      .select((value) => value.requireValue.showFastScroller);
  ProviderListenable<FinampLoopMode> get loopMode =>
      finampSettingsProvider.select((value) => value.requireValue.loopMode);
  ProviderListenable<bool> get autoloadLastQueueOnStartup =>
      finampSettingsProvider.select(
        (value) => value.requireValue.autoloadLastQueueOnStartup,
      );
  ProviderListenable<bool> get volumeNormalizationActive =>
      finampSettingsProvider.select(
        (value) => value.requireValue.volumeNormalizationActive,
      );
  ProviderListenable<double> get volumeNormalizationIOSBaseGain =>
      finampSettingsProvider.select(
        (value) => value.requireValue.volumeNormalizationIOSBaseGain,
      );
  ProviderListenable<VolumeNormalizationMode> get volumeNormalizationMode =>
      finampSettingsProvider.select(
        (value) => value.requireValue.volumeNormalizationMode,
      );
  ProviderListenable<bool> get hasCompletedDownloadsServiceMigration =>
      finampSettingsProvider.select(
        (value) => value.requireValue.hasCompletedDownloadsServiceMigration,
      );
  ProviderListenable<bool> get requireWifiForDownloads => finampSettingsProvider
      .select((value) => value.requireValue.requireWifiForDownloads);
  ProviderListenable<bool> get onlyShowFullyDownloaded => finampSettingsProvider
      .select((value) => value.requireValue.onlyShowFullyDownloaded);
  ProviderListenable<bool> get showDownloadsWithUnknownLibrary =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showDownloadsWithUnknownLibrary,
      );
  ProviderListenable<int> get maxConcurrentDownloads => finampSettingsProvider
      .select((value) => value.requireValue.maxConcurrentDownloads);
  ProviderListenable<int> get downloadWorkers => finampSettingsProvider.select(
    (value) => value.requireValue.downloadWorkers,
  );
  ProviderListenable<bool> get resyncOnStartup => finampSettingsProvider.select(
    (value) => value.requireValue.resyncOnStartup,
  );
  ProviderListenable<bool> get preferQuickSyncs => finampSettingsProvider
      .select((value) => value.requireValue.preferQuickSyncs);
  ProviderListenable<bool> get hasCompletedIsarUserMigration =>
      finampSettingsProvider.select(
        (value) => value.requireValue.hasCompletedIsarUserMigration,
      );
  ProviderListenable<FinampTranscodingCodec?> get downloadTranscodingCodec =>
      finampSettingsProvider.select(
        (value) => value.requireValue.downloadTranscodingCodec,
      );
  ProviderListenable<TranscodeDownloadsSetting> get shouldTranscodeDownloads =>
      finampSettingsProvider.select(
        (value) => value.requireValue.shouldTranscodeDownloads,
      );
  ProviderListenable<int?> get downloadTranscodeBitrate =>
      finampSettingsProvider.select(
        (value) => value.requireValue.downloadTranscodeBitrate,
      );
  ProviderListenable<bool> get shouldRedownloadTranscodes =>
      finampSettingsProvider.select(
        (value) => value.requireValue.shouldRedownloadTranscodes,
      );
  ProviderListenable<bool> get enableVibration => finampSettingsProvider.select(
    (value) => value.requireValue.enableVibration,
  );
  ProviderListenable<double> get playerScreenCoverMinimumPadding =>
      finampSettingsProvider.select(
        (value) => value.requireValue.playerScreenCoverMinimumPadding,
      );
  ProviderListenable<double> get prioritizeCoverFactor => finampSettingsProvider
      .select((value) => value.requireValue.prioritizeCoverFactor);
  ProviderListenable<bool> get suppressPlayerPadding => finampSettingsProvider
      .select((value) => value.requireValue.suppressPlayerPadding);
  ProviderListenable<bool> get hidePlayerBottomActions => finampSettingsProvider
      .select((value) => value.requireValue.hidePlayerBottomActions);
  ProviderListenable<bool> get reportQueueToServer => finampSettingsProvider
      .select((value) => value.requireValue.reportQueueToServer);
  ProviderListenable<int> get periodicPlaybackSessionUpdateFrequencySeconds =>
      finampSettingsProvider.select(
        (value) =>
            value.requireValue.periodicPlaybackSessionUpdateFrequencySeconds,
      );
  ProviderListenable<bool> get showArtistsTracksSection =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showArtistsTracksSection,
      );
  ProviderListenable<bool> get showArtistChipImage => finampSettingsProvider
      .select((value) => value.requireValue.showArtistChipImage);
  ProviderListenable<double> get playbackSpeed => finampSettingsProvider.select(
    (value) => value.requireValue.playbackSpeed,
  );
  ProviderListenable<PlaybackSpeedVisibility> get playbackSpeedVisibility =>
      finampSettingsProvider.select(
        (value) => value.requireValue.playbackSpeedVisibility,
      );
  ProviderListenable<String?> get defaultDownloadLocation =>
      finampSettingsProvider.select(
        (value) => value.requireValue.defaultDownloadLocation,
      );
  ProviderListenable<bool> get allowSplitScreen => finampSettingsProvider
      .select((value) => value.requireValue.allowSplitScreen);
  ProviderListenable<double> get splitScreenPlayerWidth =>
      finampSettingsProvider.select(
        (value) => value.requireValue.splitScreenPlayerWidth,
      );
  ProviderListenable<bool> get trackOfflineFavorites => finampSettingsProvider
      .select((value) => value.requireValue.trackOfflineFavorites);
  ProviderListenable<bool> get showProgressOnNowPlayingBar =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showProgressOnNowPlayingBar,
      );
  ProviderListenable<bool> get startInstantMixForIndividualTracks =>
      finampSettingsProvider.select(
        (value) => value.requireValue.startInstantMixForIndividualTracks,
      );
  ProviderListenable<bool> get showLyricsTimestamps => finampSettingsProvider
      .select((value) => value.requireValue.showLyricsTimestamps);
  ProviderListenable<LyricsAlignment> get lyricsAlignment =>
      finampSettingsProvider.select(
        (value) => value.requireValue.lyricsAlignment,
      );
  ProviderListenable<bool> get showStopButtonOnMediaNotification =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showStopButtonOnMediaNotification,
      );
  ProviderListenable<bool> get showSeekControlsOnMediaNotification =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showSeekControlsOnMediaNotification,
      );
  ProviderListenable<LyricsFontSize> get lyricsFontSize =>
      finampSettingsProvider.select(
        (value) => value.requireValue.lyricsFontSize,
      );
  ProviderListenable<bool> get showLyricsScreenAlbumPrelude =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showLyricsScreenAlbumPrelude,
      );
  ProviderListenable<KeepScreenOnOption> get keepScreenOnOption =>
      finampSettingsProvider.select(
        (value) => value.requireValue.keepScreenOnOption,
      );
  ProviderListenable<bool> get keepScreenOnWhilePluggedIn =>
      finampSettingsProvider.select(
        (value) => value.requireValue.keepScreenOnWhilePluggedIn,
      );
  ProviderListenable<bool> get hasDownloadedPlaylistInfo =>
      finampSettingsProvider.select(
        (value) => value.requireValue.hasDownloadedPlaylistInfo,
      );
  ProviderListenable<FinampTranscodingStreamingFormat>
  get transcodingStreamingFormat => finampSettingsProvider.select(
    (value) => value.requireValue.transcodingStreamingFormat,
  );
  ProviderListenable<FinampFeatureChipsConfiguration>
  get featureChipsConfiguration => finampSettingsProvider.select(
    (value) => value.requireValue.featureChipsConfiguration,
  );
  ProviderListenable<bool> get showCoversOnAlbumScreen => finampSettingsProvider
      .select((value) => value.requireValue.showCoversOnAlbumScreen);
  ProviderListenable<bool> get bufferDisableSizeConstraints =>
      finampSettingsProvider.select(
        (value) => value.requireValue.bufferDisableSizeConstraints,
      );
  ProviderListenable<int> get bufferSizeMegabytes => finampSettingsProvider
      .select((value) => value.requireValue.bufferSizeMegabytes);
  ProviderListenable<int> get downloadSizeWarningCutoff =>
      finampSettingsProvider.select(
        (value) => value.requireValue.downloadSizeWarningCutoff,
      );
  ProviderListenable<bool> get allowDeleteFromServer => finampSettingsProvider
      .select((value) => value.requireValue.allowDeleteFromServer);
  ProviderListenable<bool> get oneLineMarqueeTextButton =>
      finampSettingsProvider.select(
        (value) => value.requireValue.oneLineMarqueeTextButton,
      );
  ProviderListenable<bool> get showAlbumReleaseDateOnPlayerScreen =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showAlbumReleaseDateOnPlayerScreen,
      );
  ProviderListenable<ReleaseDateFormat> get releaseDateFormat =>
      finampSettingsProvider.select(
        (value) => value.requireValue.releaseDateFormat,
      );
  ProviderListenable<String?> get lastUsedDownloadLocationId =>
      finampSettingsProvider.select(
        (value) => value.requireValue.lastUsedDownloadLocationId,
      );
  ProviderListenable<Duration> get audioFadeOutDuration =>
      finampSettingsProvider.select(
        (value) => value.requireValue.audioFadeOutDuration,
      );
  ProviderListenable<Duration> get audioFadeInDuration => finampSettingsProvider
      .select((value) => value.requireValue.audioFadeInDuration);
  ProviderListenable<AutoOfflineOption> get autoOffline =>
      finampSettingsProvider.select((value) => value.requireValue.autoOffline);
  ProviderListenable<bool> get autoOfflineListenerActive =>
      finampSettingsProvider.select(
        (value) => value.requireValue.autoOfflineListenerActive,
      );
  ProviderListenable<ItemSwipeActions> get itemSwipeActionLeftToRight =>
      finampSettingsProvider.select(
        (value) => value.requireValue.itemSwipeActionLeftToRight,
      );
  ProviderListenable<ItemSwipeActions> get itemSwipeActionRightToLeft =>
      finampSettingsProvider.select(
        (value) => value.requireValue.itemSwipeActionRightToLeft,
      );
  ProviderListenable<ArtistType> get defaultArtistType => finampSettingsProvider
      .select((value) => value.requireValue.defaultArtistType);
  ProviderListenable<double> get currentVolume => finampSettingsProvider.select(
    (value) => value.requireValue.currentVolume,
  );
  ProviderListenable<int> get playOnStaleDelay => finampSettingsProvider.select(
    (value) => value.requireValue.playOnStaleDelay,
  );
  ProviderListenable<int> get playOnReconnectionDelay => finampSettingsProvider
      .select((value) => value.requireValue.playOnReconnectionDelay);
  ProviderListenable<bool> get enablePlayon =>
      finampSettingsProvider.select((value) => value.requireValue.enablePlayon);
  ProviderListenable<bool> get autoReloadQueue => finampSettingsProvider.select(
    (value) => value.requireValue.autoReloadQueue,
  );
  ProviderListenable<bool> get showShuffleButtonOnMediaNotification =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showShuffleButtonOnMediaNotification,
      );
  ProviderListenable<bool> get showFavoriteButtonOnMediaNotification =>
      finampSettingsProvider.select(
        (value) => value.requireValue.showFavoriteButtonOnMediaNotification,
      );
  ProviderListenable<ScreenSize?> get screenSize =>
      finampSettingsProvider.select((value) => value.requireValue.screenSize);
  ProviderListenable<CuratedItemSelectionType>
  get genreCuratedItemSelectionTypeTracks => finampSettingsProvider.select(
    (value) => value.requireValue.genreCuratedItemSelectionTypeTracks,
  );
  ProviderListenable<CuratedItemSelectionType>
  get genreCuratedItemSelectionTypeAlbums => finampSettingsProvider.select(
    (value) => value.requireValue.genreCuratedItemSelectionTypeAlbums,
  );
  ProviderListenable<CuratedItemSelectionType>
  get genreCuratedItemSelectionTypeArtists => finampSettingsProvider.select(
    (value) => value.requireValue.genreCuratedItemSelectionTypeArtists,
  );
  ProviderListenable<List<GenreItemSections>> get genreItemSectionsOrder =>
      finampSettingsProvider.select(
        (value) => value.requireValue.genreItemSectionsOrder,
      );
  ProviderListenable<bool> get genreFilterArtistScreens =>
      finampSettingsProvider.select(
        (value) => value.requireValue.genreFilterArtistScreens,
      );
  ProviderListenable<bool> get genreListsInheritSorting =>
      finampSettingsProvider.select(
        (value) => value.requireValue.genreListsInheritSorting,
      );
  ProviderListenable<List<CuratedItemSelectionType>>
  get genreItemSectionFilterChipOrder => finampSettingsProvider.select(
    (value) => value.requireValue.genreItemSectionFilterChipOrder,
  );
  ProviderListenable<bool> get applyFilterOnGenreChipTap =>
      finampSettingsProvider.select(
        (value) => value.requireValue.applyFilterOnGenreChipTap,
      );
  ProviderListenable<CuratedItemSelectionType>
  get artistCuratedItemSelectionType => finampSettingsProvider.select(
    (value) => value.requireValue.artistCuratedItemSelectionType,
  );
  ProviderListenable<List<CuratedItemSelectionType>>
  get artistItemSectionFilterChipOrder => finampSettingsProvider.select(
    (value) => value.requireValue.artistItemSectionFilterChipOrder,
  );
  ProviderListenable<List<ArtistItemSections>> get artistItemSectionsOrder =>
      finampSettingsProvider.select(
        (value) => value.requireValue.artistItemSectionsOrder,
      );
  ProviderListenable<bool> get autoSwitchItemCurationType =>
      finampSettingsProvider.select(
        (value) => value.requireValue.autoSwitchItemCurationType,
      );
  ProviderListenable<bool> get genreFilterPlaylists => finampSettingsProvider
      .select((value) => value.requireValue.genreFilterPlaylists);
  ProviderListenable<SleepTimer?> get sleepTimer =>
      finampSettingsProvider.select((value) => value.requireValue.sleepTimer);
  ProviderListenable<bool> get clearQueueOnStopEvent => finampSettingsProvider
      .select((value) => value.requireValue.clearQueueOnStopEvent);
  ProviderListenable<double> get playbackPitch => finampSettingsProvider.select(
    (value) => value.requireValue.playbackPitch,
  );
  ProviderListenable<bool> get syncPlaybackSpeedAndPitch =>
      finampSettingsProvider.select(
        (value) => value.requireValue.syncPlaybackSpeedAndPitch,
      );
  ProviderListenable<bool> get useHighContrastColors => finampSettingsProvider
      .select((value) => value.requireValue.useHighContrastColors);
  ProviderListenable<bool> get hasCompletedDownloadsFileOwnerMigration =>
      finampSettingsProvider.select(
        (value) => value.requireValue.hasCompletedDownloadsFileOwnerMigration,
      );
  ProviderListenable<TileAdditionalInfoType?> tileAdditionalInfoType(
    ContentType tabContentType,
  ) => finampSettingsProvider.select(
    (value) => value.requireValue.tileAdditionalInfoType[tabContentType],
  );
  ProviderListenable<bool> get rpcEnabled =>
      finampSettingsProvider.select((value) => value.requireValue.rpcEnabled);
  ProviderListenable<DiscordRpcIcon> get rpcIcon =>
      finampSettingsProvider.select((value) => value.requireValue.rpcIcon);
  ProviderListenable<bool> get autoExpandPlayerScreen => finampSettingsProvider
      .select((value) => value.requireValue.autoExpandPlayerScreen);
  ProviderListenable<bool> get preferAddingToFavoritesOverPlaylists =>
      finampSettingsProvider.select(
        (value) => value.requireValue.preferAddingToFavoritesOverPlaylists,
      );
  ProviderListenable<bool> get previousTracksExpanded => finampSettingsProvider
      .select((value) => value.requireValue.previousTracksExpanded);
  ProviderListenable<bool> get autoplayRestoredQueue => finampSettingsProvider
      .select((value) => value.requireValue.autoplayRestoredQueue);
  ProviderListenable<bool> get preferNextUpPrepending => finampSettingsProvider
      .select((value) => value.requireValue.preferNextUpPrepending);
  ProviderListenable<bool> get rememberLastUsedPlaybackActionRowPage =>
      finampSettingsProvider.select(
        (value) => value.requireValue.rememberLastUsedPlaybackActionRowPage,
      );
  ProviderListenable<PlaybackActionRowPage> get lastUsedPlaybackActionRowPage =>
      finampSettingsProvider.select(
        (value) => value.requireValue.lastUsedPlaybackActionRowPage,
      );
  ProviderListenable<Color?> get accentColor =>
      finampSettingsProvider.select((value) => value.requireValue.accentColor);
  ProviderListenable<ThemeMode> get themeMode =>
      finampSettingsProvider.select((value) => value.requireValue.themeMode);
  ProviderListenable<Locale?> get locale =>
      finampSettingsProvider.select((value) => value.requireValue.locale);
  ProviderListenable<bool> get hasCompletedThemeModeLocaleMigration =>
      finampSettingsProvider.select(
        (value) => value.requireValue.hasCompletedThemeModeLocaleMigration,
      );
  ProviderListenable<Color?> get systemAccentColor => finampSettingsProvider
      .select((value) => value.requireValue.systemAccentColor);
  ProviderListenable<bool> get useSystemAccentColor => finampSettingsProvider
      .select((value) => value.requireValue.useSystemAccentColor);
  ProviderListenable<bool> get useMonochromeIcon => finampSettingsProvider
      .select((value) => value.requireValue.useMonochromeIcon);
  ProviderListenable<PlaybackActionRowPage>
  get lastUsedPlaybackActionRowPageForQueueMenu =>
      finampSettingsProvider.select(
        (value) => value.requireValue.lastUsedPlaybackActionRowPageForQueueMenu,
      );
  ProviderListenable<bool> get radioEnabled =>
      finampSettingsProvider.select((value) => value.requireValue.radioEnabled);
  ProviderListenable<RadioMode> get radioMode =>
      finampSettingsProvider.select((value) => value.requireValue.radioMode);
  ProviderListenable<bool> get duckOnAudioInterruption => finampSettingsProvider
      .select((value) => value.requireValue.duckOnAudioInterruption);
  ProviderListenable<bool> get forceAudioOffloadingOnAndroid =>
      finampSettingsProvider.select(
        (value) => value.requireValue.forceAudioOffloadingOnAndroid,
      );
  ProviderListenable<MultichannelHandlingSetting>
  get multichannelHandlingSetting => finampSettingsProvider.select(
    (value) => value.requireValue.multichannelHandlingSetting,
  );
  ProviderListenable<PreviousTracksPersistenceMode>
  get previousTracksPersistenceMode => finampSettingsProvider.select(
    (value) => value.requireValue.previousTracksPersistenceMode,
  );
  ProviderListenable<FinampHomeScreenConfiguration>
  get homeScreenConfiguration => finampSettingsProvider.select(
    (value) => value.requireValue.homeScreenConfiguration,
  );
  ProviderListenable<int> get gridImageSize => finampSettingsProvider.select(
    (value) => value.requireValue.gridImageSize,
  );
  ProviderListenable<bool> get amoledTheme =>
      finampSettingsProvider.select((value) => value.requireValue.amoledTheme);
  ProviderListenable<bool> get useAndroidGainEffect => finampSettingsProvider
      .select((value) => value.requireValue.useAndroidGainEffect);
  ProviderListenable<int> get homeScreenImageSize => finampSettingsProvider
      .select((value) => value.requireValue.homeScreenImageSize);
  ProviderListenable<ClientCertificate?> get clientCertificate =>
      finampSettingsProvider.select(
        (value) => value.requireValue.clientCertificate,
      );
  ProviderListenable<DownloadProfile> get downloadTranscodingProfile =>
      finampSettingsProvider.select(
        (value) => value.requireValue.downloadTranscodingProfile,
      );
  ProviderListenable<DownloadLocation> get internalTrackDir =>
      finampSettingsProvider.select(
        (value) => value.requireValue.internalTrackDir,
      );
  ProviderListenable<Duration> get bufferDuration => finampSettingsProvider
      .select((value) => value.requireValue.bufferDuration);
}

// Needs import of 'package:collection/collection.dart' in parent file
class _LengthEqualsIterable<E> extends DelegatingIterable<E> {
  _LengthEqualsIterable(super.base);

  @override
  bool operator ==(Object other) {
    return other is _LengthEqualsIterable && other.length == length;
  }

  @override
  int get hashCode => Object.hash(length, '_LengthEqualsIterable');
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$finampSettingsHash() => r'298d6dcfef9bacbabf1c0d39f1b0c4155f511639';

/// See also [finampSettings].
@ProviderFor(finampSettings)
final finampSettingsProvider = StreamProvider<FinampSettings>.internal(
  finampSettings,
  name: r'finampSettingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$finampSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FinampSettingsRef = StreamProviderRef<FinampSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
